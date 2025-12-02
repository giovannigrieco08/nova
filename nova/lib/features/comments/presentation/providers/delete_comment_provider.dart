import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/delete_comment.dart';
import 'comments_notifier.dart';

/// Provider for DeleteComment use case
///
/// Usage:
/// ```dart
/// final deleteComment = ref.read(deleteCommentProvider);
/// await deleteComment(commentId: '123');
/// ```
final deleteCommentProvider = Provider<DeleteComment>((ref) {
  final repository = ref.read(commentsRepositoryProvider);
  return DeleteComment(repository);
});

/// State notifier for delete operation
///
/// Manages the async state of deleting a comment.
/// Handles loading, success, and error states.
class DeleteCommentNotifier extends StateNotifier<AsyncValue<void>> {
  final DeleteComment _deleteComment;

  DeleteCommentNotifier(this._deleteComment) : super(const AsyncValue.data(null));

  /// Execute delete operation
  ///
  /// Returns result indicating success or error type.
  Future<DeleteOperationResult> execute({required String commentId}) async {
    state = const AsyncValue.loading();

    try {
      await _deleteComment(commentId: commentId);
      state = const AsyncValue.data(null);
      return DeleteOperationResult.success;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);

      // Determine error type
      if (e.toString().contains('not found') ||
          e.toString().contains('NotFoundException')) {
        return DeleteOperationResult.notFound;
      }
      if (e.toString().contains('unauthorized') ||
          e.toString().contains('UnauthorizedException')) {
        return DeleteOperationResult.unauthorized;
      }
      if (e.toString().contains('already deleted') ||
          e.toString().contains('AlreadyDeletedException')) {
        return DeleteOperationResult.alreadyDeleted;
      }

      return DeleteOperationResult.error;
    }
  }
}

/// Delete operation result
enum DeleteOperationResult {
  /// Comment was successfully deleted
  success,
  /// Comment not found
  notFound,
  /// User not authorized to delete
  unauthorized,
  /// Comment already deleted
  alreadyDeleted,
  /// Generic error
  error,
}

/// Provider for delete operation state
final deleteCommentNotifierProvider =
    StateNotifierProvider.autoDispose<DeleteCommentNotifier, AsyncValue<void>>((ref) {
  final deleteComment = ref.read(deleteCommentProvider);
  return DeleteCommentNotifier(deleteComment);
});
