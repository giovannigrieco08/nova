import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/comments_notifier.dart';
import '../providers/reply_mode_notifier.dart';
import '../providers/delete_comment_provider.dart';
import '../widgets/comment_card.dart';
import '../widgets/comment_input_field.dart';
import '../widgets/comment_sort_toggle.dart';
import '../widgets/empty_comments_state.dart';
import '../widgets/delete_confirmation_dialog.dart';

/// CommentsSheet Screen
///
/// Fullscreen bottom sheet displaying comments for an event.
/// Platform-adaptive: CupertinoPageScaffold (iOS) vs Scaffold (Android).
///
/// **T091**: Platform-specific refresh controls
///   - iOS: CupertinoSliverRefreshControl
///   - Android: Material RefreshIndicator
///
/// **T093**: Infinite scroll with 80% threshold
/// **T096**: Pull-to-refresh with cache clearing
/// **T097**: Virtualized list with ListView.builder for 60fps
///
/// Features:
/// - Adaptive title bar with comment count
/// - Pull-to-refresh support
/// - Empty state when no comments
/// - Sticky comment input field at bottom
/// - Loading/error states
/// - Infinite scroll pagination
/// - Real-time updates via WebSocket
///
/// Usage:
/// ```dart
/// // iOS
/// Navigator.push(context, CupertinoPageRoute(
///   builder: (_) => CommentsSheet(eventId: eventId, eventTitle: title),
/// ));
///
/// // Android
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => CommentsSheet(eventId: eventId, eventTitle: title),
/// ));
/// ```
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
  ReplyModeState? _previousReplyModeState;

  /// Scroll controller for infinite scroll detection
  late final ScrollController _scrollController;

  /// Threshold for loading more (80% of scroll extent)
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

  /// T093: Detect scroll position near bottom (80% threshold)
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Check if we've scrolled past 80% threshold
    if (maxScroll > 0 && currentScroll >= maxScroll * _loadMoreThreshold) {
      // Trigger load more
      ref.read(commentsNotifierProvider(widget.eventId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsNotifierProvider(widget.eventId));
    final replyModeState = ref.watch(replyModeNotifierProvider(widget.eventId));

    // T060: Announce reply mode changes to screen readers
    _announceReplyModeChanges(context, replyModeState);
    _previousReplyModeState = replyModeState;

    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Semantics(
            header: true,
            label: commentsAsync.whenOrNull(
                  data: (state) =>
                      'Schermo dei commenti, ${state.totalCount} ${state.totalCount == 1 ? 'commento' : 'commenti'}',
                ) ??
                'Schermo dei commenti',
            child: commentsAsync.whenOrNull(
                  data: (state) => Text(
                    '${state.totalCount} ${state.totalCount == 1 ? 'commento' : 'commenti'}',
                    style: NovaTextStyles.h3,
                  ),
                ) ??
                const Text('Commenti'),
          ),
          backgroundColor: NovaColors.background(context),
          border: null,
        ),
        backgroundColor: NovaColors.background(context),
        child: SafeArea(
          child: _buildBody(context, ref, commentsAsync),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Semantics(
            header: true,
            label: commentsAsync.whenOrNull(
                  data: (state) =>
                      'Schermo dei commenti, ${state.totalCount} ${state.totalCount == 1 ? 'commento' : 'commenti'}',
                ) ??
                'Schermo dei commenti',
            child: commentsAsync.whenOrNull(
                  data: (state) => Text(
                    '${state.totalCount} ${state.totalCount == 1 ? 'commento' : 'commenti'}',
                    style: NovaTextStyles.h3,
                  ),
                ) ??
                const Text('Commenti'),
          ),
          backgroundColor: NovaColors.background(context),
          elevation: 0,
        ),
        backgroundColor: NovaColors.background(context),
        body: _buildBody(context, ref, commentsAsync),
      );
    }
  }

  /// T060: Announce reply mode changes to screen readers
  void _announceReplyModeChanges(BuildContext context, ReplyModeState newState) {
    // Skip if first build or no change
    if (_previousReplyModeState == null) return;
    if (_previousReplyModeState!.isReplyMode == newState.isReplyMode &&
        _previousReplyModeState!.targetComment?.id == newState.targetComment?.id) {
      return;
    }

    // Build announcement message
    String announcement;
    if (newState.isReplyMode) {
      final authorName = newState.targetComment?.authorName ?? 'Utente';
      announcement = 'Modalità risposta attiva. Rispondi a $authorName.';
    } else {
      announcement = 'Modalità risposta terminata. Scrivi un nuovo commento.';
    }

    // Announce to screen readers
    SemanticsService.announce(announcement, TextDirection.ltr);
  }

  /// T072: Handle delete comment with confirmation dialog
  Future<void> _handleDeleteComment(
    BuildContext context,
    WidgetRef ref,
    String commentId,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDeleteConfirmationDialog(context: context);

    if (confirmed != true || !context.mounted) return;

    // Execute delete
    final deleteNotifier = ref.read(deleteCommentNotifierProvider.notifier);
    final result = await deleteNotifier.execute(commentId: commentId);

    if (context.mounted) {
      _showDeleteFeedback(context, result);

      // Refresh comments list on success
      if (result == DeleteOperationResult.success) {
        await ref
            .read(commentsNotifierProvider(widget.eventId).notifier)
            .refresh();
      }
    }
  }

  /// Show feedback based on delete operation result
  void _showDeleteFeedback(BuildContext context, DeleteOperationResult result) {
    final (message, backgroundColor) = switch (result) {
      DeleteOperationResult.success => ('Commento eliminato', NovaColors.successLight),
      DeleteOperationResult.notFound => ('Commento non trovato', NovaColors.errorLight),
      DeleteOperationResult.unauthorized => ('Non puoi eliminare questo commento', NovaColors.errorLight),
      DeleteOperationResult.alreadyDeleted => ('Commento già eliminato', NovaColors.warningLight),
      DeleteOperationResult.error => ('Errore durante l\'eliminazione', NovaColors.errorLight),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<CommentsState> commentsAsync,
  ) {
    final replyModeState = ref.watch(replyModeNotifierProvider(widget.eventId));

    return Column(
      children: [
        // Reply mode header (purple banner when replying to a comment)
        if (replyModeState.isReplyMode) _buildReplyModeHeader(context, ref, replyModeState),

        // T101: Sort toggle below title (only show when we have comments)
        commentsAsync.maybeWhen(
          data: (state) => state.comments.isNotEmpty
              ? _buildSortToggle(context, ref, state)
              : const SizedBox.shrink(),
          orElse: () => const SizedBox.shrink(),
        ),

        // Comments list (expanded to fill available space)
        Expanded(
          child: commentsAsync.when(
            data: (state) {
              if (state.isEmpty) {
                return const EmptyCommentsState();
              }

              // T091: Platform-specific refresh controls
              if (Platform.isIOS) {
                return _buildIOSCommentsList(context, ref, state);
              } else {
                return _buildAndroidCommentsList(context, ref, state);
              }
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => Center(
              child: Semantics(
                liveRegion: true,
                label: 'Errore nel caricamento dei commenti',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: NovaColors.textTertiaryLight,
                    ),
                    SizedBox(height: NovaSpacing.m),
                    Text(
                      'Errore nel caricamento dei commenti',
                      style: NovaTextStyles.body.copyWith(
                        color: NovaColors.textSecondaryLight,
                      ),
                    ),
                    SizedBox(height: NovaSpacing.s),
                    Semantics(
                      button: true,
                      label: 'Riprova a caricare i commenti',
                      child: TextButton(
                        onPressed: () {
                          ref
                              .read(commentsNotifierProvider(widget.eventId).notifier)
                              .refresh();
                        },
                        child: const Text('Riprova'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Divider above input field
        Divider(
          height: 1,
          thickness: 1,
          color: NovaColors.dividerLight,
        ),

        // Comment input field (sticky at bottom)
        CommentInputField(
          eventId: widget.eventId,
          replyModeState: replyModeState,
        ),
      ],
    );
  }

  /// T091: Build iOS comments list with CupertinoSliverRefreshControl
  Widget _buildIOSCommentsList(
    BuildContext context,
    WidgetRef ref,
    CommentsState state,
  ) {
    return Semantics(
      label: 'Lista commenti, scorri verso il basso per aggiornare',
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // iOS-native refresh control
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              await ref
                  .read(commentsNotifierProvider(widget.eventId).notifier)
                  .refresh();
            },
          ),

          // T097: Virtualized list with SliverList.builder
          SliverPadding(
            padding: EdgeInsets.only(
              top: NovaSpacing.m,
              bottom: NovaSpacing.l,
            ),
            sliver: SliverList.separated(
              itemCount: state.comments.length + (state.hasMore || state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: NovaColors.dividerLight,
              ),
              itemBuilder: (context, index) {
                // T094: Loading indicator at list bottom
                if (index == state.comments.length) {
                  return _buildLoadingIndicator(state);
                }

                final comment = state.comments[index];
                final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                return CommentCard(
                  comment: comment,
                  eventId: widget.eventId,
                  currentUserId: currentUserId,
                  onDelete: comment.userId == currentUserId
                      ? () => _handleDeleteComment(context, ref, comment.id)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// T091: Build Android comments list with RefreshIndicator
  Widget _buildAndroidCommentsList(
    BuildContext context,
    WidgetRef ref,
    CommentsState state,
  ) {
    return Semantics(
      label: 'Lista commenti, scorri verso il basso per aggiornare',
      child: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(commentsNotifierProvider(widget.eventId).notifier)
              .refresh();
        },
        // T097: Virtualized list with ListView.builder for 60fps
        child: ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: NovaSpacing.m,
            bottom: NovaSpacing.l,
          ),
          // Extra item for loading indicator when paginating
          itemCount: state.comments.length + (state.hasMore || state.isLoadingMore ? 1 : 0),
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 1,
            color: NovaColors.dividerLight,
          ),
          itemBuilder: (context, index) {
            // T094: Loading indicator at list bottom
            if (index == state.comments.length) {
              return _buildLoadingIndicator(state);
            }

            final comment = state.comments[index];
            final currentUserId = Supabase.instance.client.auth.currentUser?.id;
            return CommentCard(
              comment: comment,
              eventId: widget.eventId,
              currentUserId: currentUserId,
              onDelete: comment.userId == currentUserId
                  ? () => _handleDeleteComment(context, ref, comment.id)
                  : null,
            );
          },
        ),
      ),
    );
  }

  /// T094/T095: Build loading indicator or end-of-list indicator
  Widget _buildLoadingIndicator(CommentsState state) {
    if (state.isLoadingMore) {
      // Show loading spinner while fetching more
      return Padding(
        padding: EdgeInsets.symmetric(vertical: NovaSpacing.l),
        child: Center(
          child: Platform.isIOS
              ? const CupertinoActivityIndicator()
              : const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      );
    }

    if (!state.hasMore) {
      // T095: End of list indicator
      return Padding(
        padding: EdgeInsets.symmetric(vertical: NovaSpacing.l),
        child: Center(
          child: Text(
            'Tutti i commenti caricati',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textTertiaryLight,
            ),
          ),
        ),
      );
    }

    // Has more but not loading - show nothing (will trigger on scroll)
    return const SizedBox.shrink();
  }

  /// T101: Build sort toggle with platform-adaptive controls
  Widget _buildSortToggle(
    BuildContext context,
    WidgetRef ref,
    CommentsState state,
  ) {
    return Column(
      children: [
        CommentSortToggle(
          currentSort: state.sortOrder,
          onSortChanged: (newSort) {
            // T102: Reset scroll position when sort changes
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
            ref
                .read(commentsNotifierProvider(widget.eventId).notifier)
                .changeSortOrder(newSort);
          },
          isLoading: state.isSorting,
        ),
        // Divider below sort toggle
        Divider(
          height: 1,
          thickness: 1,
          color: NovaColors.dividerLight,
        ),
      ],
    );
  }

  /// Builds reply mode header with purple background and close button
  Widget _buildReplyModeHeader(
    BuildContext context,
    WidgetRef ref,
    ReplyModeState replyModeState,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      decoration: BoxDecoration(
        color: NovaColors.primaryLight.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: NovaColors.primaryLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Reply icon
          Icon(
            Icons.reply,
            size: 16,
            color: NovaColors.primaryLight,
          ),

          SizedBox(width: NovaSpacing.xs),

          // Reply header text
          Expanded(
            child: Text(
              replyModeState.replyHeaderText ?? 'Rispondi',
              style: NovaTextStyles.bodyBold.copyWith(
                color: NovaColors.primaryLight,
              ),
            ),
          ),

          // Close button
          Semantics(
            button: true,
            label: 'Annulla risposta',
            child: GestureDetector(
              onTap: () {
                ref.read(replyModeNotifierProvider(widget.eventId).notifier).cancelReply();
              },
              child: Icon(
                Icons.close,
                size: 20,
                color: NovaColors.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
