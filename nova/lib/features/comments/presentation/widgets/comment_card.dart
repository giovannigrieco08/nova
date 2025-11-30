import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/comment.dart';
import '../providers/reply_mode_notifier.dart';
import '../providers/report_comment_provider.dart';
import '../providers/mention_navigation_provider.dart';
import 'like_button.dart';
import 'comment_actions_menu.dart';
import 'report_dialog.dart';
import 'mention_text.dart';

/// CommentCard Widget
///
/// Displays a single comment with avatar, author name, timestamp, text, and like count.
/// Instagram-inspired design with clean layout.
///
/// Layout:
/// - Avatar (40px circle) + Name (bold) + Timestamp on same line
/// - Comment text below (max lines: auto-expand)
/// - Like button + count below text (optional - Phase 4)
///
/// Features:
/// - Relative timestamp (e.g., "2h fa", "Ieri", "15 Gen 2025")
/// - "(modificato)" indicator if edited
/// - Avatar with initials fallback
/// - Truncated text with "altro" expansion (future enhancement)
class CommentCard extends ConsumerWidget {
  final Comment comment;
  final String eventId;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const CommentCard({
    super.key,
    required this.comment,
    required this.eventId,
    this.currentUserId,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibilityLabel = _buildAccessibilityLabel();

    // T064: Wrap with CommentActionsMenu for long-press/swipe actions
    return CommentActionsMenu(
      comment: comment,
      currentUserId: currentUserId,
      onReply: comment.isTopLevel ? () {
        ref.read(replyModeNotifierProvider(eventId).notifier).startReply(comment);
      } : null,
      onReport: () => _showReportDialog(context, ref),
      onCopy: () => copyCommentToClipboard(context, comment),
      onDelete: onDelete,
      onEdit: onEdit,
      child: Semantics(
        label: accessibilityLabel,
        child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.m,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _buildAvatar(),

            SizedBox(width: NovaSpacing.s),

            // Comment content (name, timestamp, text)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Timestamp
                  Row(
                    children: [
                      // Author name (bold)
                      Text(
                        comment.authorName ?? 'Unknown',
                        style: NovaTextStyles.bodyBold,
                      ),

                      SizedBox(width: NovaSpacing.xs),

                      // Timestamp (relative)
                      Text(
                        comment.getFormattedTimestamp(DateTime.now()),
                        style: NovaTextStyles.caption.copyWith(
                          color: NovaColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: NovaSpacing.xs),

                  // Comment text with @mention support
                  // T112: Render @mentions as tappable RichText
                  // T113-T115: Tap handler navigates to profile
                  comment.isDeleted
                      ? Text(
                          comment.displayText,
                          style: NovaTextStyles.body.copyWith(
                            color: NovaColors.textTertiaryLight,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : MentionText(
                          text: comment.displayText,
                          style: NovaTextStyles.body.copyWith(
                            color: NovaColors.textPrimaryLight,
                          ),
                          onMentionTap: (username) async {
                            final result = await ref
                                .read(mentionNavigationProvider.notifier)
                                .navigateToProfile(context, username);
                            if (context.mounted) {
                              showMentionNavigationFeedback(context, result);
                            }
                          },
                        ),

                  // Like button and Reply button (Phase 4-5)
                  if (!comment.isDeleted) ...[
                    SizedBox(height: NovaSpacing.xs),
                    Row(
                      children: [
                        // Like button
                        LikeButton(
                          commentId: comment.id,
                          initialLikeCount: comment.likeCount,
                          initialIsLiked: comment.isLikedByCurrentUser,
                        ),

                        SizedBox(width: NovaSpacing.m),

                        // Reply button (T056: Phase 5)
                        // Only show for top-level comments (not replies)
                        if (comment.parentCommentId == null)
                          Semantics(
                            button: true,
                            label: 'Rispondi al commento di ${comment.authorName}',
                            child: GestureDetector(
                              onTap: () {
                                ref
                                    .read(replyModeNotifierProvider(eventId).notifier)
                                    .startReply(comment);
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: NovaColors.textTertiaryLight,
                                  ),
                                  SizedBox(width: NovaSpacing.xxs),
                                  Text(
                                    'Rispondi',
                                    style: NovaTextStyles.caption.copyWith(
                                      color: NovaColors.textTertiaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Thread indicator (T057: Phase 5)
                    // Shows reply count for top-level comments with replies
                    if (comment.isTopLevel && comment.hasReplies) ...[
                      SizedBox(height: NovaSpacing.xs),
                      Semantics(
                        label: '${comment.replyCount} ${comment.replyCount == 1 ? "risposta" : "risposte"}',
                        child: Row(
                          children: [
                            Text(
                              '└─',
                              style: NovaTextStyles.caption.copyWith(
                                color: NovaColors.primaryLight,
                                fontFamily: 'monospace',
                              ),
                            ),
                            SizedBox(width: NovaSpacing.xs),
                            Text(
                              '${comment.replyCount} ${comment.replyCount == 1 ? "risposta" : "risposte"}',
                              style: NovaTextStyles.caption.copyWith(
                                color: NovaColors.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// T065: Show report dialog and handle submission
  Future<void> _showReportDialog(BuildContext context, WidgetRef ref) async {
    final dialogResult = await showReportDialog(
      context: context,
      commentId: comment.id,
    );

    if (dialogResult != null && context.mounted) {
      // Submit report via use case
      final reportNotifier = ref.read(reportCommentNotifierProvider.notifier);
      final submitResult = await reportNotifier.submitReport(
        commentId: comment.id,
        reason: dialogResult.reason,
        details: dialogResult.additionalDetails,
      );

      if (context.mounted) {
        _showReportFeedback(context, submitResult);
      }
    }
  }

  /// Show feedback based on report submission result
  void _showReportFeedback(BuildContext context, ReportSubmissionResult result) {
    final (message, backgroundColor) = switch (result) {
      ReportSubmissionResult.success => ('Segnalazione inviata', NovaColors.successLight),
      ReportSubmissionResult.duplicate => ('Hai già segnalato questo commento', NovaColors.warningLight),
      ReportSubmissionResult.validationError => ('I dettagli sono troppo lunghi (max 500 caratteri)', NovaColors.errorLight),
      ReportSubmissionResult.error => ('Errore durante l\'invio. Riprova più tardi.', NovaColors.errorLight),
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

  /// Build accessibility label for screen readers
  String _buildAccessibilityLabel() {
    final author = comment.authorName ?? 'Utente sconosciuto';
    final timestamp = comment.getFormattedTimestamp(DateTime.now());
    final text = comment.displayText;
    final likeCount = comment.likeCount;

    final buffer = StringBuffer();
    buffer.write('Commento di $author, $timestamp. ');
    buffer.write(text);

    if (likeCount > 0) {
      buffer.write('. $likeCount ${likeCount == 1 ? "mi piace" : "mi piace"}');
    }

    return buffer.toString();
  }

  /// Avatar with image or initials fallback
  ///
  /// T130: Optimized with CachedNetworkImage for efficient image loading
  /// - Shows skeleton placeholder while loading
  /// - Falls back to initials on error
  Widget _buildAvatar() {
    final hasAvatar = comment.authorAvatarUrl != null;
    final initials = _getInitials(comment.authorName ?? 'U');

    if (hasAvatar) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: comment.authorAvatarUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildInitialsFallback(initials),
          errorWidget: (context, url, error) => _buildInitialsFallback(initials),
        ),
      );
    }

    // Fallback: Initials
    return _buildInitialsFallback(initials);
  }

  /// Build initials fallback avatar
  Widget _buildInitialsFallback(String initials) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: NovaColors.dividerLight,
      child: Text(
        initials,
        style: NovaTextStyles.bodyBold.copyWith(
          color: NovaColors.textPrimaryLight,
        ),
      ),
    );
  }

  /// Get initials from name (e.g., "Marco Rossi" -> "MR")
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}
