import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/comment.dart';
import '../providers/reply_mode_notifier.dart';
import 'like_button.dart';

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

  const CommentCard({
    super.key,
    required this.comment,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibilityLabel = _buildAccessibilityLabel();

    return Semantics(
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

                  // Comment text
                  Text(
                    comment.displayText,
                    style: NovaTextStyles.body.copyWith(
                      color: comment.isDeleted
                          ? NovaColors.textTertiaryLight
                          : NovaColors.textPrimaryLight,
                      fontStyle:
                          comment.isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
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
  Widget _buildAvatar() {
    final hasAvatar = comment.authorAvatarUrl != null;

    if (hasAvatar) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: NovaColors.dividerLight,
        backgroundImage: CachedNetworkImageProvider(
          comment.authorAvatarUrl!,
        ),
      );
    }

    // Fallback: Initials
    final initials = _getInitials(comment.authorName ?? 'U');
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
