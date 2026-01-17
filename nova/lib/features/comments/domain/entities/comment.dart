/// Comment Entity
///
/// Business entity representing a comment on an event.
/// Supports up to 3-level threading, soft deletion, and moderation.
///
/// Nesting structure:
/// - depth 0: Top-level comment
/// - depth 1: Reply to top-level
/// - depth 2: Reply to depth 1
/// - depth 3: Reply to depth 2 (max, cannot have replies)
///
/// Constitutional Principle 5 (SPEC_FIRST): Domain layer is framework-agnostic
/// and can be tested without Flutter.
class Comment {
  /// Maximum allowed nesting depth for comments
  static const int maxDepth = 3;

  final String id;
  final String eventId;
  final String userId;
  final String? parentCommentId;
  final int depth; // Nesting level: 0=top-level, 1-3=replies
  final String text;

  // Denormalized counters
  final int likeCount;
  final int replyCount;
  final int reportCount;

  // Soft delete (GDPR compliance)
  final DateTime? deletedAt;
  final String? deletedByUserId;

  // Moderation
  final DateTime? hiddenAt;
  final String? hiddenReason;
  final String? moderatorId;

  // Audit
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Related entities (populated by repository)
  final String? authorName;
  final String? authorAvatarUrl;
  final String? authorClass;
  final String? authorRole;
  final bool isLikedByCurrentUser;
  final List<Comment>? replies; // Lazy-loaded replies

  const Comment({
    required this.id,
    required this.eventId,
    required this.userId,
    this.parentCommentId,
    this.depth = 0,
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

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /// Returns true if this comment has been soft-deleted
  bool get isDeleted => deletedAt != null;

  /// Returns true if this comment has been hidden by moderators or auto-hide
  bool get isHidden => hiddenAt != null;

  /// Returns true if this is a reply (has a parent comment)
  bool get isReply => parentCommentId != null;

  /// Returns true if this is a top-level comment (no parent)
  bool get isTopLevel => parentCommentId == null;

  /// Returns true if this comment can receive replies (depth < maxDepth)
  bool get canHaveReplies => depth < maxDepth;

  /// Returns true if this comment has been edited (updated_at != created_at)
  bool get isEdited => updatedAt != null && updatedAt != createdAt;

  /// Returns true if this comment can still be edited (within 5-minute window)
  bool canEdit(DateTime now) {
    if (isDeleted || isHidden) return false;
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
    return createdAt.isAfter(fiveMinutesAgo);
  }

  /// Returns true if the current user is the author
  bool isOwnedBy(String currentUserId) => userId == currentUserId;

  /// Returns true if the author is a moderator
  bool get isModeratorComment => authorRole == 'moderator';

  /// Returns the display text (original text or deletion placeholder)
  String get displayText {
    if (isDeleted) {
      return '[Commento eliminato]';
    }
    return text;
  }

  /// Returns relative timestamp string (e.g., "2h fa", "Ieri", "15 Gen 2025")
  ///
  /// Rules:
  /// - <1 minute: "Ora"
  /// - <1 hour: "Xm fa"
  /// - <24 hours: "Xh fa"
  /// - Yesterday: "Ieri"
  /// - <7 days: "X giorni fa"
  /// - >=7 days: "15 Gen 2025" (absolute date)
  String getRelativeTimestamp(DateTime now) {
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Ora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m fa';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h fa';
    } else if (difference.inDays == 1) {
      return 'Ieri';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      // Absolute date format: "15 Gen 2025"
      final months = [
        'Gen',
        'Feb',
        'Mar',
        'Apr',
        'Mag',
        'Giu',
        'Lug',
        'Ago',
        'Set',
        'Ott',
        'Nov',
        'Dic'
      ];
      return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
    }
  }

  /// Returns formatted timestamp with edit indicator
  ///
  /// Examples:
  /// - "2h fa"
  /// - "5 min fa (modificato)"
  String getFormattedTimestamp(DateTime now) {
    final relative = getRelativeTimestamp(now);
    if (isEdited) {
      return '$relative (modificato)';
    }
    return relative;
  }

  /// Returns true if this comment has replies
  bool get hasReplies => replyCount > 0;

  /// Returns true if this comment has likes
  bool get hasLikes => likeCount > 0;

  /// Returns abbreviated like count for display (e.g., "1K+" for >999)
  String get formattedLikeCount {
    if (likeCount > 999) {
      return '${(likeCount / 1000).floor()}K+';
    }
    return likeCount.toString();
  }

  // ============================================================================
  // COPYTO HELPER
  // ============================================================================

  Comment copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? parentCommentId,
    int? depth,
    String? text,
    int? likeCount,
    int? replyCount,
    int? reportCount,
    DateTime? deletedAt,
    String? deletedByUserId,
    DateTime? hiddenAt,
    String? hiddenReason,
    String? moderatorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorName,
    String? authorAvatarUrl,
    String? authorClass,
    String? authorRole,
    bool? isLikedByCurrentUser,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      depth: depth ?? this.depth,
      text: text ?? this.text,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      reportCount: reportCount ?? this.reportCount,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedByUserId: deletedByUserId ?? this.deletedByUserId,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      hiddenReason: hiddenReason ?? this.hiddenReason,
      moderatorId: moderatorId ?? this.moderatorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorClass: authorClass ?? this.authorClass,
      authorRole: authorRole ?? this.authorRole,
      isLikedByCurrentUser:
          isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      replies: replies ?? this.replies,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Comment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Comment(id: $id, eventId: $eventId, userId: $userId, text: ${text.substring(0, text.length > 50 ? 50 : text.length)}..., createdAt: $createdAt)';
  }
}
