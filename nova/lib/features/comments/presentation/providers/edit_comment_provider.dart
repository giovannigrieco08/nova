import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comment.dart';
import '../../domain/usecases/edit_comment.dart';
import 'comments_notifier.dart';

/// Provider for EditComment use case
final editCommentUseCaseProvider = Provider<EditComment>((ref) {
  final repository = ref.read(commentsRepositoryProvider);
  return EditComment(repository);
});

/// Edit comment state
///
/// Tracks the state of an edit operation including:
/// - Which comment is being edited
/// - Current text in the editor
/// - Loading/error states
class EditCommentState {
  final String? commentId;
  final String? originalText;
  final String currentText;
  final bool isEditing;
  final bool isSaving;
  final String? error;

  const EditCommentState({
    this.commentId,
    this.originalText,
    this.currentText = '',
    this.isEditing = false,
    this.isSaving = false,
    this.error,
  });

  EditCommentState copyWith({
    String? commentId,
    String? originalText,
    String? currentText,
    bool? isEditing,
    bool? isSaving,
    String? error,
    bool clearError = false,
    bool clearCommentId = false,
  }) {
    return EditCommentState(
      commentId: clearCommentId ? null : (commentId ?? this.commentId),
      originalText: clearCommentId ? null : (originalText ?? this.originalText),
      currentText: currentText ?? this.currentText,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error,
    );
  }

  /// Check if text has changed from original
  bool get hasChanges => currentText.trim() != originalText?.trim();

  /// Check if save button should be enabled
  bool get canSave =>
      hasChanges &&
      currentText.trim().isNotEmpty &&
      currentText.trim().length <= 500 &&
      !isSaving;

  /// Character count
  int get characterCount => currentText.length;

  /// Check if approaching limit
  bool get isApproachingLimit => characterCount >= 450;

  /// Initial state
  static const initial = EditCommentState();
}

/// Edit comment result
enum EditResult {
  success,
  windowExpired,
  validationError,
  unauthorized,
  notFound,
  error,
}

/// Edit comment notifier
///
/// **T106**: Edit mode UI state management
/// **T107**: Save handler implementation
/// **T110**: Error handling
///
/// Manages the edit flow:
/// 1. Start edit mode (store original text)
/// 2. Track text changes
/// 3. Save with validation
/// 4. Handle errors gracefully
class EditCommentNotifier extends StateNotifier<EditCommentState> {
  final EditComment _editComment;
  final Ref _ref;
  final String _eventId;

  EditCommentNotifier(this._editComment, this._ref, this._eventId)
      : super(EditCommentState.initial);

  /// Start editing a comment
  ///
  /// Pre-fills input with current text and enters edit mode.
  void startEdit(Comment comment) {
    state = EditCommentState(
      commentId: comment.id,
      originalText: comment.text,
      currentText: comment.text,
      isEditing: true,
    );
  }

  /// Cancel edit mode
  void cancelEdit() {
    state = EditCommentState.initial;
  }

  /// Update current text (called on text field change)
  void updateText(String text) {
    state = state.copyWith(
      currentText: text,
      clearError: true,
    );
  }

  /// Save edited comment
  ///
  /// **T107**: Validate, submit to server, update local state
  /// **T110**: Handle errors with user-friendly messages
  Future<EditResult> saveEdit() async {
    if (!state.canSave) return EditResult.validationError;

    final commentId = state.commentId;
    if (commentId == null) return EditResult.error;

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updatedComment = await _editComment(
        commentId: commentId,
        newText: state.currentText.trim(),
      );

      // Update comment in the list
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .updateComment(updatedComment);

      // Exit edit mode
      state = EditCommentState.initial;

      return EditResult.success;
    } on EditWindowExpiredException {
      state = state.copyWith(
        isSaving: false,
        error: 'Tempo scaduto per modifica (>5 min)',
      );
      return EditResult.windowExpired;
    } on EditValidationException catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.message,
      );
      return EditResult.validationError;
    } catch (e) {
      final errorString = e.toString();

      if (errorString.contains('unauthorized') ||
          errorString.contains('UnauthorizedException')) {
        state = state.copyWith(
          isSaving: false,
          error: 'Non puoi modificare questo commento',
        );
        return EditResult.unauthorized;
      }

      if (errorString.contains('not found') ||
          errorString.contains('NotFoundException')) {
        state = state.copyWith(
          isSaving: false,
          error: 'Commento non trovato',
        );
        return EditResult.notFound;
      }

      if (errorString.contains('profanity') ||
          errorString.contains('inappropriate')) {
        state = state.copyWith(
          isSaving: false,
          error: 'Il commento contiene linguaggio inappropriato',
        );
        return EditResult.validationError;
      }

      if (errorString.contains('edit window') ||
          errorString.contains('5 min')) {
        state = state.copyWith(
          isSaving: false,
          error: 'Tempo scaduto per modifica (>5 min)',
        );
        return EditResult.windowExpired;
      }

      state = state.copyWith(
        isSaving: false,
        error: 'Errore durante il salvataggio. Riprova.',
      );
      return EditResult.error;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for edit comment state (per event)
final editCommentNotifierProvider =
    StateNotifierProvider.family<EditCommentNotifier, EditCommentState, String>(
        (ref, eventId) {
  final editComment = ref.read(editCommentUseCaseProvider);
  return EditCommentNotifier(editComment, ref, eventId);
});
