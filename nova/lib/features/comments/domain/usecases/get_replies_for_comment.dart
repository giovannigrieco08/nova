import '../entities/comment.dart';
import '../repositories/comments_repository_interface.dart';

/// GetRepliesForComment Use Case
///
/// Fetches all replies for a specific comment.
/// Used for expanding thread view.
///
/// Business Rules:
/// - Only returns direct replies (parent_comment_id = commentId)
/// - Sorted by created_at ascending (oldest first)
/// - Excludes deleted replies (unless you're the author)
/// - Excludes hidden replies (auto-hidden by reports)
///
/// **FR-031**: Students can reply to comments (1-level threading)
/// **FR-032**: Replies display indented under parent comment
///
/// Usage:
/// ```dart
/// final getReplies = ref.read(getRepliesForCommentProvider);
/// try {
///   final replies = await getReplies(commentId: '123');
///   // Display replies in thread
/// } on NetworkException catch (_) {
///   // Show "Nessuna connessione"
/// }
/// ```
class GetRepliesForComment {
  final CommentsRepositoryInterface _repository;

  GetRepliesForComment(this._repository);

  /// Execute use case
  ///
  /// Returns list of Comment entities (replies to parent comment).
  /// Empty list if no replies exist.
  /// Throws NetworkException on connectivity issues.
  Future<List<Comment>> call({
    required String commentId,
  }) async {
    return await _repository.getRepliesForComment(
      commentId: commentId,
    );
  }
}
