import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/moderator_remove_comment.dart';
import '../../domain/usecases/moderator_restore_comment.dart';
import 'comments_notifier.dart';

/// Provider for ModeratorRemoveComment use case
final moderatorRemoveCommentProvider = Provider<ModeratorRemoveComment>((ref) {
  final repository = ref.read(commentsRepositoryProvider);
  return ModeratorRemoveComment(repository);
});

/// Provider for ModeratorRestoreComment use case
final moderatorRestoreCommentProvider =
    Provider<ModeratorRestoreComment>((ref) {
  final repository = ref.read(commentsRepositoryProvider);
  return ModeratorRestoreComment(repository);
});

/// State notifier for moderator actions
///
/// Manages the async state of moderator comment actions.
class ModeratorActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final ModeratorRemoveComment _removeComment;
  final ModeratorRestoreComment _restoreComment;

  ModeratorActionsNotifier(this._removeComment, this._restoreComment)
      : super(const AsyncValue.data(null));

  /// Remove a comment as moderator
  ///
  /// Returns result indicating success or error type.
  Future<ModeratorActionResult> remove({
    required String commentId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _removeComment(commentId: commentId, reason: reason);
      state = const AsyncValue.data(null);
      return ModeratorActionResult.success;
    } on ValidationException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return ModeratorActionResult.validationError;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);

      if (e.toString().contains('not found') ||
          e.toString().contains('NotFoundException')) {
        return ModeratorActionResult.notFound;
      }
      if (e.toString().contains('unauthorized') ||
          e.toString().contains('UnauthorizedException')) {
        return ModeratorActionResult.unauthorized;
      }
      if (e.toString().contains('already hidden') ||
          e.toString().contains('AlreadyHiddenException')) {
        return ModeratorActionResult.alreadyHidden;
      }

      return ModeratorActionResult.error;
    }
  }

  /// Restore a hidden comment as moderator
  ///
  /// Returns result indicating success or error type.
  Future<ModeratorActionResult> restore({required String commentId}) async {
    state = const AsyncValue.loading();

    try {
      await _restoreComment(commentId: commentId);
      state = const AsyncValue.data(null);
      return ModeratorActionResult.success;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);

      if (e.toString().contains('not found') ||
          e.toString().contains('NotFoundException')) {
        return ModeratorActionResult.notFound;
      }
      if (e.toString().contains('unauthorized') ||
          e.toString().contains('UnauthorizedException')) {
        return ModeratorActionResult.unauthorized;
      }
      if (e.toString().contains('not hidden') ||
          e.toString().contains('NotHiddenException')) {
        return ModeratorActionResult.notHidden;
      }

      return ModeratorActionResult.error;
    }
  }
}

/// Moderator action result
enum ModeratorActionResult {
  /// Action completed successfully
  success,

  /// Comment not found
  notFound,

  /// User not authorized (not a moderator)
  unauthorized,

  /// Comment already hidden
  alreadyHidden,

  /// Comment is not hidden (for restore)
  notHidden,

  /// Validation error (e.g., empty reason)
  validationError,

  /// Generic error
  error,
}

/// Provider for moderator actions state
final moderatorActionsNotifierProvider = StateNotifierProvider.autoDispose<
    ModeratorActionsNotifier, AsyncValue<void>>((ref) {
  final removeComment = ref.read(moderatorRemoveCommentProvider);
  final restoreComment = ref.read(moderatorRestoreCommentProvider);
  return ModeratorActionsNotifier(removeComment, restoreComment);
});
