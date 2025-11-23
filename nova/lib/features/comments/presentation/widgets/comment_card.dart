import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/comment.dart';
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
class CommentCard extends StatelessWidget {
  final Comment comment;

  const CommentCard({
    super.key,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
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

                  // Like button (T047: Phase 4 - User Story 2)
                  if (!comment.isDeleted) ...[
                    SizedBox(height: NovaSpacing.xs),
                    LikeButton(
                      commentId: comment.id,
                      initialLikeCount: comment.likeCount,
                      initialIsLiked: comment.isLikedByCurrentUser,
                    ),
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
