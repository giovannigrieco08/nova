import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/comment.dart';
import '../providers/replies_provider.dart';
import 'comment_card.dart';

/// CommentThread Widget
///
/// Displays a parent comment with its replies in threaded view.
/// Supports up to 3 levels of nesting (depth 0-3).
///
/// Layout:
/// - Parent comment (full width, depth 0 by default)
/// - Replies indented based on depth (32px per level)
/// - Recursive rendering for nested replies
///
/// Features:
/// - Automatic reply loading via GetRepliesForComment use case
/// - Collapse/expand functionality with smooth animation (T058)
/// - Default collapse if >3 replies
/// - Recursive thread rendering for multi-level nesting
///
/// **FR-031**: Students can reply to comments (up to 3-level threading)
/// **FR-032**: Replies display indented under parent comment
///
/// Usage:
/// ```dart
/// CommentThread(
///   parentComment: comment,
///   eventId: '123',
///   depth: 0, // Optional, defaults to 0
/// )
/// ```
class CommentThread extends ConsumerStatefulWidget {
  final Comment parentComment;
  final String eventId;
  /// Current depth level (0=top-level, 1-3=nested)
  final int depth;

  const CommentThread({
    super.key,
    required this.parentComment,
    required this.eventId,
    this.depth = 0,
  });

  @override
  ConsumerState<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends ConsumerState<CommentThread>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = true; // Default value, updated in initState based on reply count

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Default collapse if >3 replies (T058 requirement)
    // We'll check this when replies are loaded
    if (widget.parentComment.replyCount > 3) {
      _isExpanded = false;
      _animationController.value = 0.0;
    } else {
      _isExpanded = true;
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fetch replies for this parent comment
    final repliesAsync = ref.watch(
      repliesProviderFamily(widget.parentComment.id),
    );

    // Calculate reply depth (parent's depth + 1)
    final replyDepth = widget.depth + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent comment (with current depth)
        CommentCard(
          comment: widget.parentComment,
          eventId: widget.eventId,
          depth: widget.depth,
        ),

        // Replies section
        repliesAsync.when(
          data: (replies) {
            if (replies.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expansion toggle button (only if has replies)
                _buildExpansionToggle(replies.length),

                // Animated replies list
                SizeTransition(
                  sizeFactor: _animation,
                  child: Column(
                    children: replies.map((reply) {
                      // Recursive rendering: if reply has its own replies,
                      // use CommentThread recursively, otherwise just CommentCard
                      if (reply.hasReplies && replyDepth < Comment.maxDepth) {
                        return CommentThread(
                          parentComment: reply,
                          eventId: widget.eventId,
                          depth: replyDepth,
                        );
                      } else {
                        return CommentCard(
                          comment: reply,
                          eventId: widget.eventId,
                          depth: replyDepth,
                        );
                      }
                    }).toList(),
                  ),
                ),
              ],
            );
          },
          loading: () => Padding(
            padding: EdgeInsets.only(left: NovaSpacing.xxxxl),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NovaColors.primary(context),
                ),
              ),
            ),
          ),
          error: (error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Builds the expansion toggle button
  Widget _buildExpansionToggle(int replyCount) {
    return Semantics(
      button: true,
      label: _isExpanded
          ? 'Nascondi $replyCount ${replyCount == 1 ? "risposta" : "risposte"}'
          : 'Mostra $replyCount ${replyCount == 1 ? "risposta" : "risposte"}',
      child: GestureDetector(
        onTap: _toggleExpansion,
        child: Padding(
          padding: EdgeInsets.only(
            left: NovaSpacing.m + 40 + NovaSpacing.s, // Avatar width + spacing
            top: NovaSpacing.xs,
            bottom: NovaSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated chevron icon
              AnimatedRotation(
                turns: _isExpanded ? 0.25 : 0.0, // 90 degrees when expanded
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: NovaColors.primaryLight,
                ),
              ),
              SizedBox(width: NovaSpacing.xxs),
              Text(
                _isExpanded
                    ? 'Nascondi ${replyCount == 1 ? "risposta" : "risposte"}'
                    : 'Mostra $replyCount ${replyCount == 1 ? "risposta" : "risposte"}',
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
