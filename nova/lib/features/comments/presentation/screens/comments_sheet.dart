import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/comments_notifier.dart';
import '../providers/comment_input_notifier.dart';
import '../providers/reply_mode_notifier.dart';
import '../widgets/comment_card.dart';
import '../widgets/comment_input_field.dart';
import '../widgets/empty_comments_state.dart';

/// CommentsSheet Screen
///
/// Fullscreen bottom sheet displaying comments for an event.
/// Platform-adaptive: CupertinoPageScaffold (iOS) vs Scaffold (Android).
///
/// Features:
/// - Adaptive title bar with comment count
/// - Pull-to-refresh support
/// - Empty state when no comments
/// - Sticky comment input field at bottom
/// - Loading/error states
/// - Real-time updates (future enhancement)
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
class CommentsSheet extends ConsumerWidget {
  final String eventId;
  final String eventTitle;

  const CommentsSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentsNotifierProvider(eventId));

    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Semantics(
            header: true,
            label: commentsAsync.whenOrNull(
                  data: (comments) =>
                      'Schermo dei commenti, ${comments.length} ${comments.length == 1 ? 'commento' : 'commenti'}',
                ) ??
                'Schermo dei commenti',
            child: commentsAsync.whenOrNull(
                  data: (comments) => Text(
                    '${comments.length} ${comments.length == 1 ? 'commento' : 'commenti'}',
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
                  data: (comments) =>
                      'Schermo dei commenti, ${comments.length} ${comments.length == 1 ? 'commento' : 'commenti'}',
                ) ??
                'Schermo dei commenti',
            child: commentsAsync.whenOrNull(
                  data: (comments) => Text(
                    '${comments.length} ${comments.length == 1 ? 'commento' : 'commenti'}',
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

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<dynamic>> commentsAsync,
  ) {
    final replyModeState = ref.watch(replyModeNotifierProvider(eventId));

    return Column(
      children: [
        // Reply mode header (purple banner when replying to a comment)
        if (replyModeState.isReplyMode) _buildReplyModeHeader(context, ref, replyModeState),

        // Comments list (expanded to fill available space)
        Expanded(
          child: commentsAsync.when(
            data: (comments) {
              if (comments.isEmpty) {
                return const EmptyCommentsState();
              }

              return Semantics(
                label: 'Lista commenti, scorri verso il basso per aggiornare',
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(commentsNotifierProvider(eventId).notifier)
                        .refresh();
                  },
                  child: ListView.separated(
                  padding: EdgeInsets.only(
                    top: NovaSpacing.medium,
                    bottom: NovaSpacing.large,
                  ),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 1,
                    color: NovaColors.dividerLight,
                  ),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return CommentCard(
                      comment: comment,
                      eventId: eventId,
                    );
                  },
                ),
                ),
              );
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
                    SizedBox(height: NovaSpacing.medium),
                    Text(
                      'Errore nel caricamento dei commenti',
                      style: NovaTypography.bodyMedium.copyWith(
                        color: NovaColors.textSecondaryLight,
                      ),
                    ),
                    SizedBox(height: NovaSpacing.small),
                    Semantics(
                      button: true,
                      label: 'Riprova a caricare i commenti',
                      child: TextButton(
                        onPressed: () {
                          ref
                              .read(commentsNotifierProvider(eventId).notifier)
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
          eventId: eventId,
          replyModeState: replyModeState,
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
        color: NovaColors.primaryLight.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: NovaColors.primaryLight.withOpacity(0.3),
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
                ref.read(replyModeNotifierProvider(eventId).notifier).cancelReply();
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
