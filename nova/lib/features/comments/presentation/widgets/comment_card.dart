import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/comment.dart';
import '../providers/reply_mode_notifier.dart';
import '../providers/report_comment_provider.dart';
import '../providers/mention_navigation_provider.dart';
import '../providers/comment_likes_notifier.dart';
import 'comment_actions_menu.dart';
import 'report_dialog.dart';
import 'mention_text.dart';

/// CommentCard Widget - Instagram-style design
///
/// Layout for TOP-LEVEL comments (depth=0):
/// [Avatar 32px] [Name · Timestamp        ] [Heart]
///               [Comment text...         ] [Count]
///               [Rispondi                ]
///
/// Layout for NESTED replies (depth 1-3, indented based on depth):
///     [Indent] [Avatar 32px] [Name · Timestamp ] [Heart]
///                            [Comment text...  ] [Count]
///                            [Rispondi         ] (hidden at depth 3)
///
/// Instagram-style: replies are same size as parent, just indented.
/// Supports up to 3 levels of nesting (depth 0-3).
/// Swipe left to reveal reply icon (fast, smooth animation).
class CommentCard extends ConsumerStatefulWidget {
  final Comment comment;
  final String eventId;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  /// Nesting depth: 0=top-level, 1-3=replies
  final int depth;
  final VoidCallback? onLikeTap;

  // Indent per nesting level (reduced from 48 for mobile UX)
  static const double _indentPerLevel = 32.0;
  // Maximum swipe distance
  static const double _maxSwipeOffset = 60.0;
  // Threshold to trigger reply
  static const double _swipeThreshold = 40.0;

  const CommentCard({
    super.key,
    required this.comment,
    required this.eventId,
    this.currentUserId,
    this.onDelete,
    this.onEdit,
    this.depth = 0,
    this.onLikeTap,
  });

  /// Whether this comment can receive replies (depth < maxDepth)
  bool get canReply => depth < Comment.maxDepth && !comment.isDeleted;

  @override
  ConsumerState<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends ConsumerState<CommentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  double _dragOffset = 0;
  bool _hasTriggeredReply = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Very fast snap back
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Only allow swipe left (negative delta)
    if (details.delta.dx < 0 || _dragOffset < 0) {
      setState(() {
        _dragOffset += details.delta.dx;
        // Clamp to max offset with resistance
        if (_dragOffset < -CommentCard._maxSwipeOffset) {
          _dragOffset = -CommentCard._maxSwipeOffset -
              (_dragOffset + CommentCard._maxSwipeOffset) * 0.2;
        }
        if (_dragOffset > 0) _dragOffset = 0;

        // Trigger haptic when crossing threshold
        if (!_hasTriggeredReply &&
            _dragOffset.abs() >= CommentCard._swipeThreshold) {
          _hasTriggeredReply = true;
          HapticFeedback.lightImpact();
        } else if (_hasTriggeredReply &&
            _dragOffset.abs() < CommentCard._swipeThreshold) {
          _hasTriggeredReply = false;
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // Check if threshold was reached to trigger reply
    // Only allow reply if depth < maxDepth
    if (_dragOffset.abs() >= CommentCard._swipeThreshold &&
        widget.canReply) {
      ref
          .read(replyModeNotifierProvider(widget.eventId).notifier)
          .startReply(widget.comment);
    }

    // Animate back to original position
    final startOffset = _dragOffset;
    _swipeController.reset();

    _swipeController.addListener(() {
      setState(() {
        _dragOffset = startOffset * (1 - _swipeController.value);
      });
    });

    _swipeController.forward().then((_) {
      _hasTriggeredReply = false;
    });
  }

  String _buildAccessibilityLabel() {
    final author = widget.comment.authorName ?? 'Utente sconosciuto';
    final timestamp = widget.comment.getFormattedTimestamp(DateTime.now());
    final text = widget.comment.displayText;
    return 'Commento di $author, $timestamp. $text';
  }

  @override
  Widget build(BuildContext context) {
    final accessibilityLabel = _buildAccessibilityLabel();

    return CommentActionsMenu(
      comment: widget.comment,
      currentUserId: widget.currentUserId,
      onReply: widget.canReply
          ? () {
              ref
                  .read(replyModeNotifierProvider(widget.eventId).notifier)
                  .startReply(widget.comment);
            }
          : null,
      onReport: () => _showReportDialog(context),
      onCopy: () => copyCommentToClipboard(context, widget.comment),
      onDelete: widget.onDelete,
      onEdit: widget.onEdit,
      child: GestureDetector(
        onHorizontalDragUpdate: widget.canReply
            ? _onHorizontalDragUpdate
            : null,
        onHorizontalDragEnd:
            widget.canReply ? _onHorizontalDragEnd : null,
        child: Stack(
          children: [
            // Reply icon (revealed on swipe)
            if (_dragOffset < 0)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 50),
                    opacity: (_dragOffset.abs() / CommentCard._swipeThreshold)
                        .clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: (_dragOffset.abs() / CommentCard._swipeThreshold)
                          .clamp(0.5, 1.0),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _hasTriggeredReply
                              ? NovaColors.primary(context)
                              : NovaColors.divider(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply,
                          size: 18,
                          color: _hasTriggeredReply
                              ? Colors.white
                              : NovaColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Comment content
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Semantics(
                label: accessibilityLabel,
                child: Container(
                  color: NovaColors.background(context),
                  padding: EdgeInsets.only(
                    // Calculate indent: base margin + (depth * indent per level)
                    left: NovaSpacing.m +
                        (widget.depth * CommentCard._indentPerLevel),
                    right: NovaSpacing.m,
                    top: NovaSpacing.xs,
                    bottom: NovaSpacing.xs,
                  ),
                  child: _buildCommentLayout(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unified comment layout (Instagram-style)
  /// Same layout for both top-level and nested - only indent differs
  Widget _buildCommentLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar (32px diameter - Instagram uses same size for all)
        _buildAvatar(radius: 16),
        SizedBox(width: NovaSpacing.s),

        // Content area
        Expanded(
          child: _buildContentColumn(context),
        ),

        // Like button + count (right side)
        if (!widget.comment.isDeleted) _buildLikeColumn(),
      ],
    );
  }

  /// Content column: Name, timestamp, text, reply button
  /// Instagram-style: same typography for all comments
  Widget _buildContentColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name + Timestamp row
        Row(
          children: [
            // Author name (bold)
            Text(
              widget.comment.authorName ?? 'Unknown',
              style: NovaTextStyles.bodyBold.copyWith(
                color: NovaColors.textPrimary(context),
                fontSize: 13,
              ),
            ),
            SizedBox(width: NovaSpacing.xs),
            // Timestamp
            Text(
              widget.comment.getFormattedTimestamp(DateTime.now()),
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textTertiary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),

        SizedBox(height: 2),

        // Comment text
        widget.comment.isDeleted
            ? Text(
                widget.comment.displayText,
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textTertiary(context),
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              )
            : MentionText(
                text: widget.comment.displayText,
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textPrimary(context),
                  fontSize: 14,
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

        SizedBox(height: 4),

        // Reply button (hidden when at max depth)
        if (widget.canReply)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref
                  .read(replyModeNotifierProvider(widget.eventId).notifier)
                  .startReply(widget.comment);
            },
            child: Text(
              'Rispondi',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textTertiary(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// Like button column with heart icon and count below
  /// Instagram-style: consistent size for all comments
  Widget _buildLikeColumn() {
    final likesState = ref.watch(commentLikesNotifierProvider(widget.comment.id));
    final likesNotifier = ref.read(commentLikesNotifierProvider(widget.comment.id).notifier);

    // Initialize likes state from comment on first render
    // Use post-frame callback to avoid modifying state during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only initialize if state hasn't been set yet (default state)
      // Check if state matches default values AND differs from comment
      final needsInit = likesState.likeCount == 0 &&
                        !likesState.isLiked &&
                        !likesState.isProcessing &&
                        (widget.comment.likeCount > 0 || widget.comment.isLikedByCurrentUser);
      if (needsInit) {
        developer.log('CommentCard: Initializing likes state from comment ${widget.comment.id}');
        likesNotifier.initializeFromComment(widget.comment);
      }
    });

    // Use state from notifier if it's been initialized (likeCount > 0, isLiked true, or isProcessing)
    // Otherwise fallback to comment data
    final isInitialized = likesState.likeCount > 0 || likesState.isLiked || likesState.isProcessing;
    final isLiked = isInitialized ? likesState.isLiked : widget.comment.isLikedByCurrentUser;
    final likeCount = isInitialized ? likesState.likeCount : widget.comment.likeCount;

    // Show error if present
    if (likesState.error != null) {
      developer.log('CommentCard: Error in likes state: ${likesState.error}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore like: ${likesState.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          // Clear error after showing
          likesNotifier.clearError();
        }
      });
    }

    return Padding(
      padding: EdgeInsets.only(left: NovaSpacing.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Heart icon
          GestureDetector(
            onTap: likesState.isProcessing
                ? null
                : () {
                    developer.log('CommentCard: Like tapped for ${widget.comment.id}, isInitialized=$isInitialized, isLiked=$isLiked');
                    // Haptic feedback on like
                    HapticFeedback.lightImpact();
                    // Initialize if first interaction (state not yet set)
                    if (!isInitialized) {
                      developer.log('CommentCard: Initializing before toggle');
                      likesNotifier.initializeFromComment(widget.comment);
                    }
                    likesNotifier.toggleLike();
                  },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 14,
                color: isLiked ? Colors.red : NovaColors.textTertiaryLight,
              ),
            ),
          ),
          // Like count (only show if > 0)
          if (likeCount > 0)
            Text(
              _formatCount(likeCount),
              style: NovaTextStyles.caption.copyWith(
                fontSize: 11,
                color: NovaColors.textTertiaryLight,
              ),
            ),
        ],
      ),
    );
  }

  /// Format count for display (e.g., 1200 -> "1.2K")
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}K';
    }
    return count.toString();
  }

  /// Build avatar with image or initials fallback
  /// Instagram-style: 32px diameter for all comments
  Widget _buildAvatar({double radius = 16}) {
    final hasAvatar = widget.comment.authorAvatarUrl != null;

    if (hasAvatar) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: NovaColors.dividerLight,
        backgroundImage: CachedNetworkImageProvider(
          widget.comment.authorAvatarUrl!,
        ),
      );
    }

    // Fallback: Initials
    final initials = _getInitials(widget.comment.authorName ?? 'U');

    return CircleAvatar(
      radius: radius,
      backgroundColor: NovaColors.dividerLight,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: NovaColors.textPrimaryLight,
        ),
      ),
    );
  }

  /// Get initials from name
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  /// Show report dialog
  Future<void> _showReportDialog(BuildContext context) async {
    final dialogResult = await showReportDialog(
      context: context,
      commentId: widget.comment.id,
    );

    if (dialogResult != null && context.mounted) {
      final reportNotifier = ref.read(reportCommentNotifierProvider.notifier);
      final submitResult = await reportNotifier.submitReport(
        commentId: widget.comment.id,
        reason: dialogResult.reason,
        details: dialogResult.additionalDetails,
      );

      if (context.mounted) {
        _showReportFeedback(context, submitResult);
      }
    }
  }

  /// Show feedback for report submission
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
}
