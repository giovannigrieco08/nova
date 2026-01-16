import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/comments_notifier.dart';
import '../providers/reply_mode_notifier.dart';
import '../providers/delete_comment_provider.dart';
import '../providers/edit_comment_provider.dart';
import '../widgets/comment_card.dart';
import '../widgets/comment_input_field.dart';
import '../widgets/empty_comments_state.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/edit_input_field.dart';
import '../../domain/entities/comment.dart';

/// Show Instagram-style comments bottom sheet
///
/// Usage:
/// ```dart
/// showCommentsSheet(
///   context: context,
///   eventId: event.id,
///   eventTitle: event.title,
/// );
/// ```
void showCommentsSheet({
  required BuildContext context,
  required String eventId,
  required String eventTitle,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    isDismissible: true,
    enableDrag: true,
    builder: (context) => CommentsSheet(
      eventId: eventId,
      eventTitle: eventTitle,
    ),
  );
}

/// CommentsSheet - Instagram-style modal bottom sheet
///
/// Features:
/// - Draggable bottom sheet (75% of screen height)
/// - Handle bar at top
/// - Title "Commenti" centered
/// - Pull-to-refresh support
/// - Infinite scroll pagination
/// - Sticky comment input at bottom
class CommentsSheet extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const CommentsSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  late final ScrollController _scrollController;
  static const double _loadMoreThreshold = 0.8;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    if (maxScroll > 0 && currentScroll >= maxScroll * _loadMoreThreshold) {
      ref.read(commentsNotifierProvider(widget.eventId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsNotifierProvider(widget.eventId));
    final replyModeState = ref.watch(replyModeNotifierProvider(widget.eventId));
    final editModeState = ref.watch(editCommentNotifierProvider(widget.eventId));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: NovaColors.background(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              _buildHandle(),

              // Title
              _buildTitle(commentsAsync),

              // Divider
              Divider(height: 1, color: NovaColors.divider(context)),

              // Reply mode header
              if (replyModeState.isReplyMode && !editModeState.isEditing)
                _buildReplyModeHeader(replyModeState),

              // Edit mode header
              if (editModeState.isEditing)
                _buildEditModeHeader(editModeState),

              // Comments list
              Expanded(
                child: commentsAsync.when(
                  data: (state) {
                    if (state.isEmpty) {
                      return const EmptyCommentsState();
                    }
                    return _buildCommentsList(state);
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => _buildErrorState(),
                ),
              ),

              // Divider
              Divider(height: 1, color: NovaColors.divider(context)),

              // Input field with keyboard padding
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SafeArea(
                  child: editModeState.isEditing
                      ? EditInputField(
                          eventId: widget.eventId,
                          onSaveSuccess: () {
                            _showFeedback('Commento modificato');
                          },
                        )
                      : CommentInputField(
                          eventId: widget.eventId,
                          replyModeState: replyModeState,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: NovaColors.textTertiary(context),
          borderRadius: NovaRadius.circularXxs,
        ),
      ),
    );
  }

  Widget _buildTitle(AsyncValue<CommentsState> commentsAsync) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Commenti',
        style: NovaTextStyles.h3.copyWith(
          fontWeight: FontWeight.w700,
          color: NovaColors.textPrimary(context),
        ),
      ),
    );
  }

  Widget _buildCommentsList(CommentsState state) {
    // Build flat list with comments + their nested replies
    final items = _buildCommentItems(state.comments);

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(commentsNotifierProvider(widget.eventId).notifier)
            .refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.xs,
          vertical: NovaSpacing.s,
        ),
        itemCount: items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _buildLoadingIndicator();
          }

          final item = items[index];
          final comment = item.comment;
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;

          return CommentCard(
            comment: comment,
            eventId: widget.eventId,
            currentUserId: currentUserId,
            isNested: item.isNested,
            onDelete: comment.userId == currentUserId
                ? () => _handleDeleteComment(comment.id)
                : null,
            onEdit: comment.userId == currentUserId && comment.canEdit(DateTime.now())
                ? () => _handleEditComment(comment)
                : null,
          );
        },
      ),
    );
  }

  /// Build flat list of comment items including nested replies
  List<_CommentItem> _buildCommentItems(List<Comment> comments) {
    final items = <_CommentItem>[];

    for (final comment in comments) {
      // Add top-level comment
      items.add(_CommentItem(comment: comment, isNested: false));

      // Add nested replies if present
      if (comment.replies != null && comment.replies!.isNotEmpty) {
        for (final reply in comment.replies!) {
          items.add(_CommentItem(comment: reply, isNested: true));
        }
      }
    }

    return items;
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: EdgeInsets.all(NovaSpacing.m),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: NovaColors.textTertiary(context),
          ),
          SizedBox(height: NovaSpacing.m),
          Text(
            'Errore nel caricamento',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
          SizedBox(height: NovaSpacing.s),
          TextButton(
            onPressed: () {
              ref
                  .read(commentsNotifierProvider(widget.eventId).notifier)
                  .refresh();
            },
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyModeHeader(ReplyModeState replyModeState) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      color: NovaColors.primary(context).withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: NovaColors.primary(context),
          ),
          SizedBox(width: NovaSpacing.xs),
          Expanded(
            child: Text(
              replyModeState.replyHeaderText ?? 'Rispondi',
              style: NovaTextStyles.bodyBold.copyWith(
                color: NovaColors.primary(context),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(replyModeNotifierProvider(widget.eventId).notifier).cancelReply();
            },
            child: Icon(
              Icons.close,
              size: 20,
              color: NovaColors.primary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditModeHeader(EditCommentState editState) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      color: NovaColors.warningLight.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            Icons.edit,
            size: 16,
            color: NovaColors.warningDark,
          ),
          SizedBox(width: NovaSpacing.xs),
          Expanded(
            child: Text(
              'Modifica commento',
              style: NovaTextStyles.bodyBold.copyWith(
                color: NovaColors.warningDark,
              ),
            ),
          ),
          if (editState.currentText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: NovaSpacing.s),
              child: Text(
                '${editState.characterCount}/500',
                style: NovaTextStyles.caption.copyWith(
                  color: editState.isApproachingLimit
                      ? NovaColors.errorLight
                      : NovaColors.textTertiaryLight,
                ),
              ),
            ),
          GestureDetector(
            onTap: () {
              ref.read(editCommentNotifierProvider(widget.eventId).notifier).cancelEdit();
            },
            child: Icon(
              Icons.close,
              size: 20,
              color: NovaColors.warningDark,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteComment(String commentId) async {
    final confirmed = await showDeleteConfirmationDialog(context: context);

    if (confirmed != true || !mounted) return;

    final deleteNotifier = ref.read(deleteCommentNotifierProvider.notifier);
    final result = await deleteNotifier.execute(commentId: commentId);

    if (mounted) {
      final message = switch (result) {
        DeleteOperationResult.success => 'Commento eliminato',
        DeleteOperationResult.notFound => 'Commento non trovato',
        DeleteOperationResult.unauthorized => 'Non puoi eliminare questo commento',
        DeleteOperationResult.alreadyDeleted => 'Commento già eliminato',
        DeleteOperationResult.error => 'Errore durante l\'eliminazione',
      };
      _showFeedback(message);

      if (result == DeleteOperationResult.success) {
        await ref
            .read(commentsNotifierProvider(widget.eventId).notifier)
            .refresh();
      }
    }
  }

  void _handleEditComment(Comment comment) {
    ref.read(replyModeNotifierProvider(widget.eventId).notifier).cancelReply();
    ref.read(editCommentNotifierProvider(widget.eventId).notifier).startEdit(comment);
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Helper class for building flat comment list with nested replies
class _CommentItem {
  final Comment comment;
  final bool isNested;

  const _CommentItem({
    required this.comment,
    required this.isNested,
  });
}
