import '../../domain/entities/comment.dart';

/// CommentModel - Data Transfer Object
///
/// Handles JSON serialization/deserialization for Supabase API responses.
/// Maps between database schema and domain entity.
///
/// Constitutional Principle 5 (SPEC_FIRST): Data layer provides implementations
/// for domain contracts. This model transforms Supabase JSON to Comment entity.
class CommentModel {
  final String id;
  final String eventId;
  final String userId;
  final String? parentCommentId;
  final String text;
  final int likeCount;
  final int replyCount;
  final int reportCount;
  final DateTime? deletedAt;
  final String? deletedByUserId;
  final DateTime? hiddenAt;
  final String? hiddenReason;
  final String? moderatorId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined profile data (from Supabase JOIN or RPC)
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorClass;
  final String? authorRole;

  // Computed field from LEFT JOIN with comment_likes table
  final bool isLikedByCurrentUser;

  // Lazy-loaded replies (not included in default queries)
  final List<CommentModel>? replies;

  const CommentModel({
    required this.id,
    required this.eventId,
    required this.userId,
    this.parentCommentId,
    required this.text,
    this.likeCount = 0,
    this.replyCount = 0,
    this.reportCount = 0,
    this.deletedAt,
    this.deletedByUserId,
    this.hiddenAt,
    this.hiddenReason,
    this.moderatorId,
    required this.createdAt,
    this.updatedAt,
    this.authorName,
    this.authorAvatarUrl,
    this.authorClass,
    this.authorRole,
    this.isLikedByCurrentUser = false,
    this.replies,
  });

  // ==========================================================================
  // JSON DESERIALIZATION (Supabase → CommentModel)
  // ==========================================================================

  /// Create CommentModel from Supabase JSON response
  ///
  /// Handles nested profile data from JOINs and optional fields.
  /// Supports recursive deserialization for replies.
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      parentCommentId: json['parent_comment_id'] as String?,
      text: json['text'] as String,
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      reportCount: json['report_count'] as int? ?? 0,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      deletedByUserId: json['deleted_by_user_id'] as String?,
      hiddenAt: json['hidden_at'] != null
          ? DateTime.parse(json['hidden_at'] as String)
          : null,
      hiddenReason: json['hidden_reason'] as String?,
      moderatorId: json['moderator_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // Profile data from JOIN (may use nested object or flat fields)
      authorName: _extractAuthorName(json),
      authorAvatarUrl: _extractAuthorAvatarUrl(json),
      authorClass: _extractAuthorClass(json),
      authorRole: _extractAuthorRole(json),
      // Like status from LEFT JOIN or computed field
      isLikedByCurrentUser: json['is_liked_by_current_user'] as bool? ?? false,
      // Replies (if included in response)
      replies: json['replies'] != null
          ? (json['replies'] as List)
              .map((reply) => CommentModel.fromJson(reply as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  // Helper methods to extract author data from nested profile object or flat fields
  static String? _extractAuthorName(Map<String, dynamic> json) {
    if (json['profiles'] != null && json['profiles'] is Map) {
      return json['profiles']['full_name'] as String?;
    }
    return json['author_name'] as String?;
  }

  static String? _extractAuthorAvatarUrl(Map<String, dynamic> json) {
    if (json['profiles'] != null && json['profiles'] is Map) {
      return json['profiles']['avatar_url'] as String?;
    }
    return json['author_avatar_url'] as String?;
  }

  static String? _extractAuthorClass(Map<String, dynamic> json) {
    if (json['profiles'] != null && json['profiles'] is Map) {
      return json['profiles']['class'] as String?;
    }
    return json['author_class'] as String?;
  }

  static String? _extractAuthorRole(Map<String, dynamic> json) {
    if (json['profiles'] != null && json['profiles'] is Map) {
      return json['profiles']['role'] as String?;
    }
    return json['author_role'] as String?;
  }

  // ==========================================================================
  // JSON SERIALIZATION (CommentModel → JSON)
  // ==========================================================================

  /// Convert CommentModel to JSON for API requests or Hive caching
  ///
  /// Omits read-only computed fields (counters handled by database triggers).
  /// Does NOT include nested replies to avoid circular serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'parent_comment_id': parentCommentId,
      'text': text,
      'like_count': likeCount,
      'reply_count': replyCount,
      'report_count': reportCount,
      'deleted_at': deletedAt?.toIso8601String(),
      'deleted_by_user_id': deletedByUserId,
      'hidden_at': hiddenAt?.toIso8601String(),
      'hidden_reason': hiddenReason,
      'moderator_id': moderatorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      // Include profile data for cache completeness
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl,
      'author_class': authorClass,
      'author_role': authorRole,
      'is_liked_by_current_user': isLikedByCurrentUser,
      // Note: replies not serialized to avoid circular references
    };
  }

  // ==========================================================================
  // DOMAIN ENTITY CONVERSION (CommentModel → Comment)
  // ==========================================================================

  /// Convert data model to domain entity
  ///
  /// Maps all fields to Comment entity with recursive conversion for replies.
  Comment toEntity() {
    return Comment(
      id: id,
      eventId: eventId,
      userId: userId,
      parentCommentId: parentCommentId,
      text: text,
      likeCount: likeCount,
      replyCount: replyCount,
      reportCount: reportCount,
      deletedAt: deletedAt,
      deletedByUserId: deletedByUserId,
      hiddenAt: hiddenAt,
      hiddenReason: hiddenReason,
      moderatorId: moderatorId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      authorClass: authorClass,
      authorRole: authorRole,
      isLikedByCurrentUser: isLikedByCurrentUser,
      replies: replies?.map((model) => model.toEntity()).toList(),
    );
  }

  // ==========================================================================
  // DOMAIN ENTITY CONVERSION (Comment → CommentModel)
  // ==========================================================================

  /// Create CommentModel from domain entity
  ///
  /// Useful for testing or when converting cached entities back to models.
  factory CommentModel.fromEntity(Comment entity) {
    return CommentModel(
      id: entity.id,
      eventId: entity.eventId,
      userId: entity.userId,
      parentCommentId: entity.parentCommentId,
      text: entity.text,
      likeCount: entity.likeCount,
      replyCount: entity.replyCount,
      reportCount: entity.reportCount,
      deletedAt: entity.deletedAt,
      deletedByUserId: entity.deletedByUserId,
      hiddenAt: entity.hiddenAt,
      hiddenReason: entity.hiddenReason,
      moderatorId: entity.moderatorId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      authorName: entity.authorName,
      authorAvatarUrl: entity.authorAvatarUrl,
      authorClass: entity.authorClass,
      authorRole: entity.authorRole,
      isLikedByCurrentUser: entity.isLikedByCurrentUser,
      replies: entity.replies?.map((e) => CommentModel.fromEntity(e)).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CommentModel(id: $id, eventId: $eventId, userId: $userId, text: ${text.substring(0, text.length > 50 ? 50 : text.length)}...)';
  }
}
