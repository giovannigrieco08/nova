import '../entities/comment.dart';
import '../repositories/comments_repository_interface.dart';

/// ReplyToComment Use Case
///
/// Posts a reply to an existing comment (1-level threading).
/// Server enforces that replies cannot have their own replies.
///
/// Business Rules:
/// - Can reply to top-level comments only (parent_comment_id = null)
/// - Cannot reply to replies (1-level threading limit enforced server-side)
/// - Reply is a regular comment with parent_comment_id set
/// - All validation rules apply (profanity, rate limits, length)
///
/// **FR-031**: Students can reply to comments (1-level threading)
/// **FR-032**: Replies display indented under parent comment
///
/// Usage:
/// ```dart
/// final replyToComment = ref.read(replyToCommentProvider);
/// try {
///   final reply = await replyToComment(
///     eventId: '123',
///     parentCommentId: '456',
///     text: 'Great point!',
///   );
///   // Reply posted successfully
/// } on ValidationException catch (e) {
///   // Show error: "Cannot reply to a reply"
/// }
/// ```
class ReplyToComment {
  final CommentsRepositoryInterface _repository;

  ReplyToComment(this._repository);

  /// Execute use case
  ///
  /// Returns newly created Comment entity (the reply).
  /// Throws ValidationException if trying to reply to a reply.
  /// Throws all other exceptions from replyToComment.
  Future<Comment> call({
    required String parentCommentId,
    required String text,
  }) async {
    // Validation happens server-side via database trigger
    // Client just needs to pass parentCommentId

    return await _repository.replyToComment(
      commentId: parentCommentId,
      text: text,
    );
  }
}
