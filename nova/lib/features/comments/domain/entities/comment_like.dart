/// CommentLike Entity
///
/// Business entity representing a user liking a specific comment.
/// Simple entity with composite primary key (comment_id, user_id).
class CommentLike {
  final String commentId;
  final String userId;
  final DateTime createdAt;
  final DateTime? deletedAt; // Soft delete for GDPR

  const CommentLike({
    required this.commentId,
    required this.userId,
    required this.createdAt,
    this.deletedAt,
  });

  /// Returns true if this like has been soft-deleted
  bool get isDeleted => deletedAt != null;

  CommentLike copyWith({
    String? commentId,
    String? userId,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return CommentLike(
      commentId: commentId ?? this.commentId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CommentLike &&
        other.commentId == commentId &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(commentId, userId);

  @override
  String toString() {
    return 'CommentLike(commentId: $commentId, userId: $userId, createdAt: $createdAt)';
  }
}
